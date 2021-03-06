// MIT License
// 
// Copyright(c) 2018 Romain Br�gier
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#pragma once

#include <memory>
#include <utility>
#include <vector>
#include <memory>
#include <string>
#include <cassert>
#include <algorithm>
#include <typeindex>
#include <map>
#include <algorithm>
#include <functional>


namespace plycpp
{
	extern const std::type_index CHAR;
	extern const std::type_index UCHAR;
	extern const std::type_index SHORT;
	extern const std::type_index USHORT;
	extern const std::type_index INT;
	extern const std::type_index UINT;
	extern const std::type_index FLOAT;
	extern const std::type_index DOUBLE;

	enum FileFormat
	{
		ASCII,
		BINARY
	};

	class Exception : public std::exception
	{
	public:
		explicit Exception(const std::string &msg)
			: _error(msg)
		{}

        explicit Exception(const char* msg)
            : _error(msg)
        {}

        ~Exception() noexcept override = default;

        const char* what() const noexcept override
        {
               return _error.what();
        }

    protected:
        std::runtime_error _error;
	};

	template<typename Key, typename T>
	struct KeyData
	{
		KeyData(const Key key, const T& data)
		{
			this->key = key;
			this->data = data;
		}

		Key key;
		T data;
	};

    class PropertyArray;
    class ElementArray;

	/// A list of elements that can be accessed through a given key for convenience.
	/// Access by key is not meant to be fast, but practical.
	template<typename Key, typename Data>
	class IndexedList
	{
	private:
		typedef KeyData<Key, std::shared_ptr<Data> > MyKeyData;
		typedef std::vector<MyKeyData>  Container;
    protected:
        typedef std::map<Key, bool> LookupTable;
	public:
		typedef typename Container::iterator iterator;
		typedef typename Container::const_iterator const_iterator;

		std::shared_ptr<Data> operator[] (const Key& key)
		{
			auto it = std::find_if(begin(), end(), [&key](const MyKeyData& a){ return a.key == key; });
			if (it != end())
				return it->data;
			else
				throw Exception("Invalid key.");
		}

		std::shared_ptr<const Data> operator[] (const Key& key) const noexcept(false)
		{
			auto it = std::find_if(begin(), end(), [&key](const MyKeyData& a){ return a.key == key; });
			if (it != end())
				return it->data;
			else
				throw Exception("Invalid key.");
		}

		void push_back(const Key& key, const std::shared_ptr<Data>& data)
		{
			container.push_back(MyKeyData(key, data));
		}

		void clear()
		{
			container.clear();
		}

		bool hasElementWithKey(const Key& key)
        {
		    return std::find_if(begin(), end(), [&key](const MyKeyData& a){ return a.key == key; }) != end();
        }

		iterator begin() { return container.begin(); };
		const_iterator begin() const { return container.begin(); };
		iterator end() { return container.end(); };
		const_iterator end() const { return container.end(); };

	private:
		Container container;
	};

    template <typename Key, typename Data>
    class PLYFile : public IndexedList<Key, Data>
    {
    protected:
        typedef std::map<Key, bool> LookupTable;

    public:
        bool hasPointCloud()
        {
            static LookupTable components {
                    std::make_pair("x", false),
                    std::make_pair("y", false),
                    std::make_pair("z", false)
            };

            if (this->hasElementWithKey("vertex")) {
                return hasComponents(components, (*this)["vertex"]->properties);
            } else {
                return false;
            }

        }

        bool hasNormals()
        {
            static LookupTable components {
                    std::make_pair("nx", false),
                    std::make_pair("ny", false),
                    std::make_pair("nz", false)
            };

            if (this->hasElementWithKey("vertex")) {
                return hasComponents(components, (*this)["vertex"]->properties);
            } else {
                return false;
            }
        }

        bool hasColors()
        {
            static LookupTable components {
                    std::make_pair("red", false),
                    std::make_pair("green", false),
                    std::make_pair("blue", false)
            };

            if (this->hasElementWithKey("vertex")) {
                return hasComponents(components, (*this)["vertex"]->properties);
            } else {
                return false;
            }
        }

        bool hasAplha()
        {
            if (this->hasElementWithKey("vertex")) {
                return (*this)["vertex"]->properties.hasElementWithKey("alpha");
            } else {
                return false;
            }
        }

    protected:
        bool hasComponents(typename IndexedList<Key, Data>::LookupTable& aComponents, IndexedList<Key, PropertyArray>& aContainer)
        {
            bool result = true;

            std::for_each(aComponents.begin(),
                          aComponents.end(),
                          [&aContainer, &result](auto& element) -> void {
                              auto key = element.first;
                              element.second = aContainer.hasElementWithKey(key);
                              result &= element.second;
                          });

            return result;
        };
    };

	typedef std::shared_ptr<const PropertyArray> PropertyArrayConstPtr;
	typedef std::shared_ptr<PropertyArray> PropertyArrayPtr;
    typedef PLYFile<std::string, ElementArray> PLYData;

	class PropertyArray
    {
	public:
		PropertyArray(std::type_index type, size_t size, bool isList = false);

		template<typename T>
		bool isOfType() const
		{
			return type == std::type_index(typeid(T));
		}

		template<typename T>
		const T* ptr() const
		{
			assert(isOfType<T>());
			return reinterpret_cast<const T*>(&data[0]);
		}

		template<typename T>
		T* ptr()
		{
			assert(isOfType<T>());
			return reinterpret_cast<T*>(data.data());
		}

		size_t size() const
		{
			assert(data.size() % stepSize == 0);
			return data.size() / stepSize;
		}

		template<typename T>
		const T& at(const size_t i) const
		{
			assert(isOfType<T>());
			assert((i+1) * stepSize <= data.size());
			return  *reinterpret_cast<const T*>(&data[i * stepSize]);
		}

		template<typename T>
		T& at(const size_t i)
		{
			assert(isOfType<T>());
			assert((i + 1) * stepSize <= data.size());
			return  *reinterpret_cast<T*>(&data[i * stepSize]);
		}

        void resize(size_t n)
        {
            size_t newSize = n * stepSize;
            data.resize(isList ? newSize * 3 : newSize);
        }

		std::vector<unsigned char> data;
		const std::type_index type;
		const unsigned int stepSize;
		const bool isList = false;
	};

	class ElementArray
	{
	public:
		explicit ElementArray(const size_t size)
			: size_(size)
		{}
		
		IndexedList<std::string, PropertyArray > properties;

		size_t size() const
		{
			return size_;
		}

        void resize(size_t n)
        {
            size_ = n;

            for (auto &property : properties) {
                property.data->resize(n);
            }
        }

	private:
		size_t size_;
	};

	/// Load PLY data
	void load(const std::string& filename, PLYData& data);

	/// Save PLY data
	void save(const std::string& filename, const PLYData& data, FileFormat format = FileFormat::BINARY);

	/// Pack n properties -- each represented by a vector of type T --
	/// into a multichannel vector (e.g. of type vector<std::array<T, n> >)
	template<typename T, typename OutputVector>
	void packProperties(std::vector<std::shared_ptr<const PropertyArray> > properties, OutputVector& output)
	noexcept(false)
	{
		output.clear();

		if (properties.empty() || !properties.front())
			throw Exception("Missing properties");

		const size_t size = properties.front()->size();
		const size_t nbProperties = properties.size();
		
		// Pointers to actual data
		std::vector<const T*> ptsData;
		for (auto& prop : properties)
		{
			// Check type consistency
			if (!prop || !prop->isOfType<T>() || prop->size() != size)
			{
				throw Exception(std::string("Missing properties or type inconsistency. I was expecting data of type ") + typeid(T).name());
			}
			ptsData.push_back(prop->ptr<T>());
		}

		// Packing
		output.resize(size);
		for (size_t i = 0; i < size; ++i)
		{
			for (size_t j = 0; j < nbProperties; ++j)
			{
				output[i][j] = ptsData[j][i];
			}
		}
	}

	/// Unpack a multichannel vector into a list of properties.
	template<typename T, typename OutputVector>
	void unpackProperties(const OutputVector& cloud, std::vector < std::shared_ptr<PropertyArray> >& properties)
	{
		const size_t size = cloud.size();
		const size_t nbProperties = properties.size();

		// Initialize and get
		// Pointers to actual property data
		std::vector<T*> ptsData;
		for (auto& prop : properties)
		{
			prop = std::make_shared<PropertyArray>(std::type_index(typeid(T)), size);
			ptsData.push_back(prop->ptr<T>());
		}

		// Copy data
		for (size_t i = 0; i < size; ++i)
		{
			for (size_t j = 0; j < nbProperties; ++j)
			{
				ptsData[j][i] = cloud[i][j];
			}
		}
	}


	template<typename T, typename Cloud>
	void toPointCloud(const PLYData& plyData, Cloud& cloud)
	{
		cloud.clear();
		auto plyVertex = plyData["vertex"];
		if (plyVertex->size() == 0)
			return;
		std::vector<std::shared_ptr<const PropertyArray> > properties { plyVertex->properties["x"], plyVertex->properties["y"], plyVertex->properties["z"] };
		packProperties<T, Cloud>(properties, cloud);
	}

	template<typename T, typename Cloud>
	void toNormalCloud(const PLYData& plyData, Cloud& cloud)
	{
		cloud.clear();
		auto plyVertex = plyData["vertex"];
		if (plyVertex->size() == 0)
			return;
		std::vector<std::shared_ptr<const PropertyArray> > properties{ plyVertex->properties["nx"], plyVertex->properties["ny"], plyVertex->properties["nz"] };
		packProperties<T, Cloud>(properties, cloud);
	}

	template<typename T, typename Cloud>
	void fromPointCloud(const Cloud& points, PLYData& plyData)
	{
		const size_t size = points.size();

		plyData.clear();

		std::vector<std::shared_ptr<PropertyArray> > positionProperties(3);
		unpackProperties<T, Cloud>(points, positionProperties);

		std::shared_ptr<ElementArray> vertex(new ElementArray(size));
		vertex->properties.push_back("x", positionProperties[0]);
		vertex->properties.push_back("y", positionProperties[1]);
		vertex->properties.push_back("z", positionProperties[2]);

		plyData.push_back("vertex", vertex);
	}

	template<typename T, typename Cloud>
	void fromPointCloudAndNormals(const Cloud& points, const Cloud& normals, PLYData& plyData) noexcept(false)
	{
		const size_t size = points.size();

		if (size != normals.size())
			throw Exception("Inconsistent size");

		
		plyData.clear();
		
		std::vector<std::shared_ptr<PropertyArray> > positionProperties(3);
		unpackProperties<T, Cloud>(points, positionProperties);

		std::vector<std::shared_ptr<PropertyArray> > normalProperties(3);
		unpackProperties<T, Cloud>(normals, normalProperties);

		std::shared_ptr<ElementArray> vertex(new ElementArray(size));
		vertex->properties.push_back("x", positionProperties[0]);
		vertex->properties.push_back("y", positionProperties[1]);
		vertex->properties.push_back("z", positionProperties[2]);

		vertex->properties.push_back("nx", normalProperties[0]);
		vertex->properties.push_back("ny", normalProperties[1]);
		vertex->properties.push_back("nz", normalProperties[2]);

		plyData.push_back("vertex", vertex);
	}

	template <typename T, typename Cloud>
	void fromPointCloudNormalsAndRGBA(const Cloud& points, const Cloud& normals, const Cloud& colors, PLYData& plyData) noexcept(false)
    {
        const size_t size = points.size();

        if (size != normals.size())
            throw Exception("Inconsistent size");


        plyData.clear();

        std::vector<std::shared_ptr<PropertyArray> > positionProperties(3);
        unpackProperties<T, Cloud>(points, positionProperties);

        std::vector<std::shared_ptr<PropertyArray> > normalProperties(3);
        unpackProperties<T, Cloud>(normals, normalProperties);

//        auto nrOfComponents = colors->

//        std::vector<std::shared_ptr<PropertyArray>> ()

        std::shared_ptr<ElementArray> vertex(new ElementArray(size));
    }

}
